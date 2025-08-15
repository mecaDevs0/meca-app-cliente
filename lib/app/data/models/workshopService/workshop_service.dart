import 'package:json_annotation/json_annotation.dart';

import '../service.dart';

part 'workshop_service.g.dart';

@JsonSerializable()
class WorkshopService {
  WorkshopService({
    this.id,
    this.value,
    this.estimatedTime,
    this.service,
    this.quickService,
    this.minTimeScheduling,
    this.description,
    this.photo,
    this.created,
  });

  factory WorkshopService.fromJson(Map<String, dynamic> json) {
    print('🔧 [WorkshopService] JSON original: $json');
    print('🔧 [WorkshopService] Service JSON: ${json['service']}');
    print('🔧 [WorkshopService] Photo: ${json['photo']}');
    
    final workshopService = _$WorkshopServiceFromJson(json);
    
    print('🔧 [WorkshopService] WorkshopService criado: ID=${workshopService.id}');
    print('🔧 [WorkshopService] Service object: ${workshopService.service}');
    print('🔧 [WorkshopService] Service name: ${workshopService.service?.name}');
    print('🔧 [WorkshopService] Service photo: ${workshopService.service?.photo}');
    print('🔧 [WorkshopService] Photo: ${workshopService.photo}');
    
    return workshopService;
  }

  String? id;
  double? value;
  double? estimatedTime;
  bool? quickService;
  double? minTimeScheduling;
  String? description;
  String? photo;
  int? created;
  Service? service;

  Map<String, dynamic> toJson() => _$WorkshopServiceToJson(this);
}
