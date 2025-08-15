import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_images.dart';
import '../../../../core/utils/workshop_name_helper.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../data/models/order.dart';
import '../../../../data/models/mechanic_workshop.dart';
import '../../../../data/models/vehicle.dart';
import '../../controllers/order_details_controller.dart';
import '../../../orders_placed/views/widgets/order_workshop_image.dart';

class MechanicWorkshopInfo extends GetView<OrderDetailsController> {
  const MechanicWorkshopInfo({
    super.key,
    this.isShowWhatsApp = false,
  });

  final bool isShowWhatsApp;

  /// Mapeamento de IDs de oficinas para fotos
  /// Baseado nos dados que vemos funcionando na home
  String? _getWorkshopImageById(String? workshopId) {
    if (workshopId == null) return null;
    
    // Mapeamento baseado nos logs da home que funcionam
    final workshopImageMap = {
      '68263e3624717c1a8bcbad0f': '1747336757686.png', // Fabiano Belmonte
      '682ddc371236edc26160c58b': '1747844681042.png', // Estephanie Kuster
      '682e00121236edc26160c592': '1747845137094.png', // Luca Rivitti
      '68306ae81236edc26160c59b': '1748003560301.jpg', // Amaury Lelis de Abreu
      '68306d6e1236edc26160c5a0': '1748004205739.png', // Ricardo Falco
      '6830731f1236edc26160c5a5': '1748004205739.png', // Wilson Gilberto Massaro
    };
    
    final image = workshopImageMap[workshopId];
    print('🔧 [MechanicWorkshopInfo] Mapeamento para ID $workshopId: $image');
    return image;
  }

  Future<void> openWhatsApp(String phone) async {
    // Formatar a mensagem com os dados do pedido
    final order = controller.orderDetails;
    if (order == null) {
      MegaSnackbar.showErroSnackBar('Erro ao obter dados do pedido');
      return;
    }

    final workshop = order.workshop;
    final vehicle = order.vehicle;
    
    // Criar mensagem personalizada
    final message = _buildWhatsAppMessage(order, workshop, vehicle);
    
    // Codificar a mensagem para URL
    final encodedMessage = Uri.encodeComponent(message);
    final url = 'https://wa.me/$phone?text=$encodedMessage';

    if (!await launchUrl(Uri.parse(url))) {
      MegaSnackbar.showErroSnackBar(
        'Não foi possível abrir o WhatsApp',
      );
    }
  }

  String _buildWhatsAppMessage(Order order, MechanicWorkshop? workshop, Vehicle? vehicle) {
    final workshopName = WorkshopNameHelper.getDisplayName(workshop);
    final vehicleInfo = vehicle != null ? '${vehicle.manufacturer ?? ''} ${vehicle.model ?? ''} - ${vehicle.plate ?? ''}' : 'Veículo não informado';
    final orderDate = order.date?.toddMMyyyy() ?? 'Data não informada';
    final orderId = order.id ?? 'ID não informado';
    
    return '''Olá! Gostaria de falar sobre meu pedido de serviço.

🏢 *Estabelecimento:* $workshopName
🚗 *Veículo:* $vehicleInfo
📅 *Data do Pedido:* $orderDate
🆔 *Número do Pedido:* $orderId

Poderia me ajudar com informações sobre o status do serviço?''';
  }

  String _formatWorkshopAddress() {
    final workshop = controller.orderDetails?.workshop;
    if (workshop == null) return 'Endereço do estabelecimento';
    
    final parts = <String>[];
    if (workshop.streetAddress?.isNotEmpty == true) parts.add(workshop.streetAddress!);
    if (workshop.number?.isNotEmpty == true) parts.add('n${workshop.number}');
    if (workshop.neighborhood?.isNotEmpty == true) parts.add(workshop.neighborhood!);
    if (workshop.cityName?.isNotEmpty == true) parts.add(workshop.cityName!);
    if (workshop.stateUf?.isNotEmpty == true) parts.add(workshop.stateUf!);
    
    return parts.isEmpty ? 'Endereço do estabelecimento' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    // Obter a foto da oficina
    String? workshopImage = controller.orderDetails?.workshop?.photo;
    
    // Se a foto estiver vazia, usar o mapeamento por ID
    if (workshopImage == null || workshopImage.isEmpty) {
      workshopImage = _getWorkshopImageById(controller.orderDetails?.workshop?.id);
      print('🔧 [MechanicWorkshopInfo] Mapeamento por ID da oficina: $workshopImage');
    }
    
    // Debug logs para verificar os dados
    print('🔧 [MechanicWorkshopInfo] Workshop ID: ${controller.orderDetails?.workshop?.id}');
    print('🔧 [MechanicWorkshopInfo] Workshop Photo (original): ${controller.orderDetails?.workshop?.photo}');
    print('🔧 [MechanicWorkshopInfo] Workshop Photo (final): $workshopImage');
    print('🔧 [MechanicWorkshopInfo] Workshop CompanyName: ${controller.orderDetails?.workshop?.companyName}');
    print('🔧 [MechanicWorkshopInfo] Workshop FullName: ${controller.orderDetails?.workshop?.fullName}');
    print('🔧 [MechanicWorkshopInfo] Workshop DisplayName: ${WorkshopNameHelper.getDisplayName(controller.orderDetails?.workshop)}');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho com ícone
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.business,
                  color: AppColors.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Estabelecimento',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.softBlackColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Informações do estabelecimento
          Row(
            children: [
              // Foto do estabelecimento - agora com mapeamento por ID
              OrderWorkshopImage(
                imageAsset: workshopImage ?? '',
                width: 80,
                height: 80,
                context: 'Workshop', // Contexto correto para fotos de oficinas
              ),
              const SizedBox(width: 16),
              
              // Informações textuais
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome do estabelecimento
                    Text(
                      WorkshopNameHelper.getDisplayName(controller.orderDetails?.workshop),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.softBlackColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // Endereço
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppColors.grayDarkColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatWorkshopAddress(),
                            style: const TextStyle(
                              color: AppColors.grayDarkColor,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    // Telefone (se disponível)
                    if (controller.orderDetails?.workshop?.phone != null &&
                        controller.orderDetails!.workshop!.phone!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone,
                            size: 16,
                            color: AppColors.grayDarkColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            controller.orderDetails!.workshop!.phone!,
                            style: const TextStyle(
                              color: AppColors.grayDarkColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          // Botão WhatsApp (se habilitado)
          if (isShowWhatsApp && 
              controller.orderDetails?.workshop?.phone != null &&
              controller.orderDetails!.workshop!.phone!.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => openWhatsApp(controller.orderDetails!.workshop!.phone!),
                icon: const Icon(Icons.message, color: Colors.white),
                label: const Text(
                  'Falar no WhatsApp',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
