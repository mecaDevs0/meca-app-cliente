import 'package:json_annotation/json_annotation.dart';

import 'budget_service_model.dart';
import 'mechanic_workshop.dart';
import 'profile.dart';
import 'vehicle.dart';
import 'workshopService/workshop_service.dart';

part 'order.g.dart';

@JsonSerializable()
class Order {
  Order({
    this.id,
    this.created,
    this.observations,
    this.date,
    this.suggestedDate,
    this.status,
    this.budgetApprovalDate,
    this.estimatedTimeForCompletion,
    this.diagnosticValue,
    this.budgetImages,
    this.totalValue,
    this.workshopServices,
    this.maintainedBudgetServices,
    this.excludedBudgetServices,
    this.paymentDate,
    this.paymentStatus,
    this.lastUpdate,
    this.serviceStartDate,
    this.serviceEndDate,
    this.reasonDisapproval,
    this.imagesDisapproval,
    this.dispute,
    this.imagesDispute,
    this.freeRepair,
    this.serviceFinishedByAdmin,
    this.profile,
    this.workshop,
    this.vehicle,
    this.hasEvaluated,
    this.budgetServices,
  });
  Order.empty()
      : id = '',
        created = 0,
        observations = '',
        date = 0,
        suggestedDate = 0,
        status = 0,
        budgetApprovalDate = 0,
        estimatedTimeForCompletion = 0,
        diagnosticValue = 0,
        budgetImages = [],
        totalValue = 0,
        workshopServices = [],
        maintainedBudgetServices = [],
        excludedBudgetServices = [],
        paymentDate = 0,
        paymentStatus = 0,
        lastUpdate = 0,
        serviceStartDate = 0,
        serviceEndDate = 0,
        reasonDisapproval = '',
        imagesDisapproval = [],
        dispute = '',
        imagesDispute = [],
        freeRepair = false,
        serviceFinishedByAdmin = false,
        profile = Profile.empty(),
        workshop = MechanicWorkshop.empty(),
        vehicle = Vehicle.empty();

  factory Order.fromJson(Map<String, dynamic> json) {
    // Debug logs para workshopServices
    print('🔧 [Order] JSON original workshopServices: ${json['workshopServices']}');
    print('🔧 [Order] Tipo de workshopServices: ${json['workshopServices']?.runtimeType}');
    
    // Mapeamento customizado para o workshop
    Map<String, dynamic> workshopData = {};
    if (json['workshop'] != null && json['workshop'] is Map<String, dynamic>) {
      final workshopJson = json['workshop'] as Map<String, dynamic>;
      
      // CORREÇÃO: Usar exatamente os mesmos campos que a API retorna
      // Não fazer mapeamento artificial, usar os dados originais
      workshopData = {
        '_id': workshopJson['id'] ?? workshopJson['_id'],
        'FullName': workshopJson['fullName'] ?? workshopJson['FullName'],
        'CompanyName': workshopJson['companyName'] ?? workshopJson['CompanyName'],
        'AccountableName': workshopJson['accountableName'] ?? workshopJson['AccountableName'],
        'Phone': workshopJson['phone'] ?? workshopJson['Phone'],
        'Cnpj': workshopJson['cnpj'] ?? workshopJson['Cnpj'],
        'ZipCode': workshopJson['zipCode'] ?? workshopJson['ZipCode'],
        'StreetAddress': workshopJson['streetAddress'] ?? workshopJson['StreetAddress'],
        'Number': workshopJson['number'] ?? workshopJson['Number'],
        'CityName': workshopJson['cityName'] ?? workshopJson['CityName'],
        'CityId': workshopJson['cityId'] ?? workshopJson['CityId'],
        'StateName': workshopJson['stateName'] ?? workshopJson['StateName'],
        'StateUf': workshopJson['stateUf'] ?? workshopJson['StateUf'],
        'StateId': workshopJson['stateId'] ?? workshopJson['StateId'],
        'Neighborhood': workshopJson['neighborhood'] ?? workshopJson['Neighborhood'],
        'Complement': workshopJson['complement'] ?? workshopJson['Complement'],
        'Latitude': workshopJson['latitude'] ?? workshopJson['Latitude'],
        'Longitude': workshopJson['longitude'] ?? workshopJson['Longitude'],
        'Photo': workshopJson['photo'] ?? workshopJson['Photo'], // Tentar ambos os campos
        'Email': workshopJson['email'] ?? workshopJson['Email'],
        'Rating': workshopJson['rating'] ?? workshopJson['Rating'],
        'Distance': workshopJson['distance'] ?? workshopJson['Distance'],
        'Reason': workshopJson['reason'] ?? workshopJson['Reason'] ?? 'Estabelecimento de confiança para serviços automotivos',
      };
      
      // Log detalhado de todos os campos do workshop
      print('🔧 [Order] Workshop JSON completo: $workshopJson');
      print('🔧 [Order] Workshop data mapeado: $workshopData');
      
      // Log para debug
      print('🔧 [Order] Photo original da API: ${workshopJson['photo']}');
      print('🔧 [Order] Photo PascalCase da API: ${workshopJson['Photo']}');
      print('🔧 [Order] Photo mapeada: ${workshopData['Photo']}');
      print('🔧 [Order] CompanyName original: ${workshopJson['companyName']}');
      print('🔧 [Order] FullName original: ${workshopJson['fullName']}');
      print('🔧 [Order] CompanyName mapeado: ${workshopData['CompanyName']}');
      print('🔧 [Order] FullName mapeado: ${workshopData['FullName']}');
      print('🔧 [Order] Workshop ID original: ${workshopJson['id']}');
      print('🔧 [Order] Workshop ID PascalCase: ${workshopJson['_id']}');
      print('🔧 [Order] Workshop ID mapeado: ${workshopData['_id']}');
    } else {
      print('🔧 [Order] Workshop data é null ou não é Map: ${json['workshop']}');
    }
    
    // Criar uma cópia do JSON com o workshop mapeado corretamente
    final modifiedJson = Map<String, dynamic>.from(json);
    if (workshopData.isNotEmpty) {
      modifiedJson['workshop'] = workshopData;
    }
    
    final order = _$OrderFromJson(modifiedJson);
    
    // Debug logs após mapeamento
    print('🔧 [Order] Order criado com ID: ${order.id}');
    print('🔧 [Order] WorkshopServices count após mapeamento: ${order.workshopServices?.length ?? 0}');
    if (order.workshopServices != null && order.workshopServices!.isNotEmpty) {
      for (int i = 0; i < order.workshopServices!.length; i++) {
        final service = order.workshopServices![i];
        print('🔧 [Order] WorkshopService ${i + 1}: ID=${service.id}');
        print('🔧 [Order] WorkshopService ${i + 1}: Service object=${service.service}');
        print('🔧 [Order] WorkshopService ${i + 1}: Service name=${service.service?.name}');
        print('🔧 [Order] WorkshopService ${i + 1}: Service photo=${service.service?.photo}');
        print('🔧 [Order] WorkshopService ${i + 1}: Photo=${service.photo}');
      }
    }
    
    return order;
  }

  String? id;
  int? created;
  String? observations;
  int? date;
  int? suggestedDate;
  int? status;
  int? budgetApprovalDate;
  int? estimatedTimeForCompletion;
  double? diagnosticValue;
  @JsonKey(defaultValue: [])
  List<String>? budgetImages;
  double? totalValue;
  @JsonKey(defaultValue: [])
  List<WorkshopService>? workshopServices;
  @JsonKey(defaultValue: [])
  List<BudgetServiceModel>? maintainedBudgetServices;
  @JsonKey(defaultValue: [])
  List<BudgetServiceModel>? excludedBudgetServices;
  int? paymentDate;
  int? lastUpdate;
  int? paymentStatus;
  int? serviceStartDate;
  int? serviceEndDate;
  String? reasonDisapproval;
  @JsonKey(defaultValue: [])
  List<String>? imagesDisapproval;
  String? dispute;
  @JsonKey(defaultValue: [])
  List<String>? imagesDispute;
  bool? freeRepair;
  bool? serviceFinishedByAdmin;
  Profile? profile;
  MechanicWorkshop? workshop;
  Vehicle? vehicle;
  bool? hasEvaluated;
  List<BudgetServiceModel>? budgetServices;

  Map<String, dynamic> toJson() => _$OrderToJson(this);

  String get formattedAddress {
    if (workshop?.streetAddress != null && workshop?.zipCode != null) {
      return '${workshop?.streetAddress}, ${workshop?.number}, ${workshop?.neighborhood}, ${workshop?.cityName} - ${workshop?.stateUf}';
    }
    return 'Sem Endereço';
  }
}
