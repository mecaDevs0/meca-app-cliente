import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/utils/workshop_name_helper.dart';
import 'order_workshop_image.dart';

class OrderWorkshopRow extends StatelessWidget {
  const OrderWorkshopRow({
    super.key,
    required this.order,
    required this.workshopName,
    required this.carBrand,
    required this.vehiclePlate,
    required this.date,
    this.workshopAddress,
  });

  final dynamic order; // Order object
  final String workshopName;
  final String carBrand;
  final String vehiclePlate;
  final String date;
  final String? workshopAddress;

  /// Mapeamento de IDs de serviços para imagens
  /// Baseado nos dados da home que estão funcionando
  String? _getServiceImageById(String? serviceId) {
    if (serviceId == null) return null;
    
    // Mapeamento baseado nos logs da home
    final serviceImageMap = {
      '682dcf291236edc26160c576': 'diagnostico-eletronico.png', // Diagnóstico eletrônico
      '6826405324717c1a8bcbad16': 'mecanica-geral.png', // Mecânica geral
      '682640c324717c1a8bcbad17': 'sistema-eletrico.png', // Auto elétrica
      '682dcd131236edc26160c572': 'alinhamento-balanceamento.png', // Alinhamento e balanceamento
      '682dcd621236edc26160c573': 'troca-filtros.png', // Troca de óleo e filtros
      '682dcdbe1236edc26160c574': 'sistema-motor.png', // Serviços de motor e câmbio
      '682dcebb1236edc26160c575': 'revisao-preventiva.png', // Revisões Preventivas
      '682dcf6e1236edc26160c577': 'funilaria-pintura.png', // Funilaria e pintura
      '682dcfc61236edc26160c578': 'martelinho-ouro.png', // Martelinho de ouro
      '682dd0751236edc26160c579': 'carros-antigos.png', // Serviços para carros antigos
      '682dd0cf1236edc26160c57a': 'carros-nacionais.png', // Oficina especializada em carros nacionais
      '682dd0e21236edc26160c57b': 'carros-importados.png', // Oficina especializada em carros importados
      '682dd0f91236edc26160c57c': 'pickups-utilitarios.png', // Oficina especializada em pick-ups
      '682dd1071236edc26160c57d': 'suvs-4x4.png', // Oficina especializada em SUVs
      '682dd11d1236edc26160c57e': 'carros-premium.png', // Oficina especializada em veículos premium
      '682dd1741236edc26160c57f': 'performance-tuning.png', // Performance/tuning
      '682dd1b31236edc26160c580': 'acessorios.png', // Instalação de acessórios
      '682dd2691236edc26160c581': 'sistema-escape.png', // Serviços de escapamento
      '682dd2b71236edc26160c582': 'sistema-direcao.png', // Serviços de direção
      '682dd2e81236edc26160c583': 'correias.png', // Troca de correia dentada
      '682dd33c1236edc26160c584': 'revisao-venda.png', // Revisão para venda
      '682dd37f1236edc26160c585': 'sistema-limpeza.png', // Lavagem técnica
      '682dd3ab1236edc26160c586': 'blindagem.png', // Blindagem
      '682dd4841236edc26160c587': 'sistema-arrefecimento.png', // Sistema de arrefecimento
      '682dd4b11236edc26160c588': 'sistema-embreagem.png', // Sistema de Embreagem
      '682dd53c1236edc26160c589': 'lava-rapido.png', // Lava Rápido
      '682dd5711236edc26160c58a': 'alinhamento-balanceamento.png', // Alinhamento simples
    };
    
    return serviceImageMap[serviceId];
  }

  @override
  Widget build(BuildContext context) {
    // Debug logs detalhados para verificar a estrutura dos dados
    print('🔧 [OrderWorkshopRow] Order ID: ${order?.id}');
    print('🔧 [OrderWorkshopRow] WorkshopServices count: ${order?.workshopServices?.length ?? 0}');
    
    // Extrair a imagem do primeiro serviço do pedido
    String? serviceImage;
    if (order?.workshopServices != null && order.workshopServices.isNotEmpty) {
      final firstService = order.workshopServices.first;
      print('🔧 [OrderWorkshopRow] First service ID: ${firstService.id}');
      print('🔧 [OrderWorkshopRow] First service object: $firstService');
      print('🔧 [OrderWorkshopRow] First service.service: ${firstService.service}');
      
      // Primeiro tentar usar a foto do Service (pode estar vazia)
      serviceImage = firstService.service?.photo;
      print('🔧 [OrderWorkshopRow] Primeiro serviço: ${firstService.service?.name}');
      print('🔧 [OrderWorkshopRow] Foto do Service (direta): ${firstService.service?.photo}');
      
      // Se a foto estiver vazia, usar o mapeamento por ID
      if (serviceImage == null || serviceImage.isEmpty) {
        print('🔧 [OrderWorkshopRow] ⚠️ Foto do serviço está vazia ou nula');
        serviceImage = _getServiceImageById(firstService.service?.id);
        print('🔧 [OrderWorkshopRow] Mapeamento por ID: $serviceImage');
        
        // Se ainda não encontrou, tentar usar a foto do WorkshopService como fallback
        if (serviceImage == null || serviceImage.isEmpty) {
          serviceImage = firstService.photo;
          print('🔧 [OrderWorkshopRow] Fallback - Foto do WorkshopService: $serviceImage');
        }
      }
    } else {
      print('🔧 [OrderWorkshopRow] ❌ Nenhum workshopService encontrado');
    }
    
    // Debug logs para verificar os dados
    print('🔧 [OrderWorkshopRow] Service Image final: $serviceImage');
    print('🔧 [OrderWorkshopRow] Workshop Name: $workshopName');
    
    return Row(
      children: [
        // Foto do serviço - agora mostra a imagem do serviço ao invés do workshop
        OrderWorkshopImage(
          imageAsset: serviceImage ?? '',
          width: 60,
          height: 60,
          context: 'ServiceCard', // Contexto correto para imagens de serviços
        ),
        const SizedBox(width: 12),
        
        // Informações do estabelecimento
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nome do estabelecimento com ícone (sem chip)
              Row(
                children: [
                  // Ícone de oficina
                  Icon(
                    Icons.build,
                    size: 18,
                    color: AppColors.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  // Nome da oficina
                  Expanded(
                    child: Text(
                      workshopName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              
              // Endereço do estabelecimento
              if (workshopAddress != null && workshopAddress!.isNotEmpty)
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        workshopAddress!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              
              const SizedBox(height: 8),
              
              // Informações do veículo (chips menores)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  // Placa
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      vehiclePlate,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                  
                  // Modelo
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Text(
                      carBrand,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                  
                  // Data
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 10,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          date,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
