class ServiceItemModel {
  ServiceItemModel({
    required this.id,
    required this.name,
    required this.price,
    required this.isApproved,
  });

  final String id;
  final String name;
  final double price;
  final bool isApproved;

  static List<ServiceItemModel> get listServices {
    final listServices = <ServiceItemModel>[
      ServiceItemModel(
        id: '1',
        name: 'Troca de óleo',
        price: 80.00,
        isApproved: true,
      ),
      ServiceItemModel(
        id: '2',
        name: 'Troca de pastilhas de freio',
        price: 180.00,
        isApproved: true,
      ),
      ServiceItemModel(
        id: '3',
        name: 'Troca de amortecedores',
        price: 280.00,
        isApproved: false,
      ),
    ];
    return listServices;
  }
}
