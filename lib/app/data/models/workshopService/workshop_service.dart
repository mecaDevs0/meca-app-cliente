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

  factory WorkshopService.fromJson(Map<String, dynamic> json) =>
      _$WorkshopServiceFromJson(json);

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
