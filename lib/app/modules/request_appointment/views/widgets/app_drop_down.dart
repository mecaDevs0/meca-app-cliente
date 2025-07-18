import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/core.dart';
import '../../../../data/models/workshopService/workshop_service.dart';
import 'package:meca_cliente/app/modules/request_appointment/controllers/request_appointment_controller.dart';

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
  final LayerLink _layerLink = LayerLink();

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

  void _updateServiceText() {
    // Atualiza o texto do campo com os serviços selecionados
    if (controller.selectedServices.isEmpty) {
      _serviceController.text = '';
    } else if (controller.selectedServices.length == 1) {
      _serviceController.text = controller.selectedServices.first.service?.name ?? 'Serviço selecionado';
    } else {
      _serviceController.text = '${controller.selectedServices.length} serviços selecionados';
    }
  }

  void _showDropdown() {
    if (widget.services.isEmpty) {
      // Se não houver serviços disponíveis, mostra uma mensagem
      Get.snackbar(
        'Atenção',
        'Não há serviços disponíveis para esta oficina.',
        backgroundColor: Colors.amber,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final RenderBox renderBox = _buttonKey.currentContext!.findRenderObject()! as RenderBox;
    final size = renderBox.size;

    // Calculando altura máxima para o dropdown baseado no número de itens
    // com limite para não ocupar toda a tela
    final maxHeight = MediaQuery.of(context).size.height * 0.4;
    final itemHeight = 52.0; // altura estimada para cada item
    final calculatedHeight = widget.services.length * itemHeight;
    final dropdownHeight = calculatedHeight > maxHeight ? maxHeight : calculatedHeight;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height),
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8.0),
            child: Container(
              height: dropdownHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4.0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: widget.services.length,
                itemBuilder: (context, index) {
                  final service = widget.services[index];
                  return ItemModal(
                    onTap: () {
                      widget.onSelected(service);
                      _updateServiceText(); // Atualiza o texto ao selecionar
                      setState(() {}); // Força atualização da UI
                    },
                    service: service,
                    isSelected: isSelected(service),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void initState() {
    super.initState();
    // Atualiza o texto inicial se já houver serviços selecionados
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateServiceText());
  }

  @override
  void dispose() {
    _hideDropdown();
    _serviceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Atualizando o texto sempre que o estado do controller mudar
    _updateServiceText();

    return CompositedTransformTarget(
      link: _layerLink,
      child: AppTextField(
        key: _buttonKey,
        controller: _serviceController,
        label: 'Serviço',
        hintText: 'Selecione o serviço',
        onTap: _toggleDropdown,
        // O parâmetro readOnly não é definido em AppTextField, então removemos
        suffixIcon: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SvgPicture.asset(
            AppImages.icDropdown,
          ),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor.withOpacity(0.05) : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                service.service?.name ?? 'Serviço',
                style: TextStyle(
                  color: AppColors.blackPrimaryColor,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            AppCheckBoxDrop(isSelected: isSelected),
          ],
        ),
      ),
    );
  }
}
